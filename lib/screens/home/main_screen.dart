import 'package:flutter/material.dart';
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
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF10131B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', isDark),
                _buildNavItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Explore', isDark),
                // Center Create (+) Button
                GestureDetector(
                  onTap: () {
                    // Navigate to Arena / Create Room
                    setState(() => _selectedIndex = 2);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D5DF6), // Royal Purple
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D5DF6).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                Obx(() {
                  final unread = chatCtrl.totalUnread;
                  return _buildNavItem(
                    3,
                    Icons.chat_bubble_rounded,
                    Icons.chat_bubble_outline_rounded,
                    'Messages',
                    isDark,
                    unread: unread,
                  );
                }),
                _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, bool isDark, {int unread = 0}) {
    final isSelected = _selectedIndex == index;
    final activeColor = const Color(0xFF6D5DF6);
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
                if (unread > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
