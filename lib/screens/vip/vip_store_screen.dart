import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/vip_controller.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/vip_avatar_decorator.dart';

class VipStoreScreen extends StatefulWidget {
  const VipStoreScreen({Key? key}) : super(key: key);

  @override
  State<VipStoreScreen> createState() => _VipStoreScreenState();
}

class _VipStoreScreenState extends State<VipStoreScreen>
    with SingleTickerProviderStateMixin {
  final VipController _vipCtrl = Get.find<VipController>();
  late TabController _categoryTabController;

  final List<String> _categories = [
    'Borders',
    'Avatar Rings',
    'Name Colors',
    'Chat Bubbles',
    'Themes',
    'Wallpapers',
  ];

  // Store Items definition
  final Map<String, List<Map<String, dynamic>>> _storeItems = {
    'Borders': [
      {'id': 'VIP 1', 'name': 'Royal Blue Shield', 'req': 1, 'desc': 'Dignified royal blue static border'},
      {'id': 'VIP 2', 'name': 'Purple Aura Glow', 'req': 2, 'desc': 'Pulsing violet ring border'},
    ],
    'Avatar Rings': [
      {'id': 'None', 'name': 'Default Ring', 'req': 0, 'desc': 'No extra rings equipped'},
      {'id': 'VIP 2', 'name': 'Elite Purple Halo', 'req': 2, 'desc': 'Soft purple pulsing rings around avatar'},
    ],
    'Name Colors': [
      {'id': 'None', 'name': 'Default Username', 'req': 0, 'desc': 'Standard name rendering'},
      {'id': 'VIP 1', 'name': 'Royal Blue Text', 'req': 1, 'desc': 'Solid royal blue name text'},
    ],
    'Chat Bubbles': [
      {'id': 'None', 'name': 'Standard Bubble', 'req': 0, 'desc': 'Default chat message format'},
      {'id': 'VIP 1', 'name': 'Blue Shield Bubble', 'req': 1, 'desc': 'Soft blue message container'},
    ],
    'Themes': [
      {'id': 'None', 'name': 'Default Gray', 'req': 0, 'desc': 'Standard dark mode design'},
      {'id': 'VIP 2', 'name': 'Violet Velvet', 'req': 2, 'desc': 'Rich violet themes with translucent cards'},
    ],
    'Wallpapers': [
      {'id': 'None', 'name': 'Default Room Wall', 'req': 0, 'desc': 'Standard wallpaper'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  String _getActiveCustomization(String category) {
    switch (category) {
      case 'Borders':
        return _vipCtrl.activeFrame.value;
      case 'Avatar Rings':
        return _vipCtrl.activeAvatarRing.value;
      case 'Name Colors':
        return _vipCtrl.activeNameColor.value;
      case 'Chat Bubbles':
        return _vipCtrl.activeChatBubble.value;
      case 'Themes':
        return _vipCtrl.activeTheme.value;
      case 'Wallpapers':
        return _vipCtrl.activeWallpaper.value;
      default:
        return 'None';
    }
  }

  void _equipItem(String category, String itemId) {
    String key = '';
    switch (category) {
      case 'Borders':
        key = 'frame';
        break;
      case 'Avatar Rings':
        key = 'ring';
        break;
      case 'Name Colors':
        key = 'nameColor';
        break;
      case 'Chat Bubbles':
        key = 'chatBubble';
        break;
      case 'Themes':
        key = 'theme';
        break;
      case 'Wallpapers':
        key = 'wallpaper';
        break;
    }

    _vipCtrl.setCustomization(key, itemId);
    Get.snackbar(
      'Cosmetic Updated',
      'Successfully equipped $itemId for $category!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Color(0xFF10B981).withOpacity(0.9),
      colorText: Colors.white,
    );
    setState(() {});
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'VIP COSMETIC STORE',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary, letterSpacing: 1.0),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.textPrimary),
        elevation: 0,
        bottom: TabBar(
          controller: _categoryTabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: context.primaryColor,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.textSecondary.withOpacity(0.6),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: Obx(() {
        final currentVip = _vipCtrl.vipLevel.value;

        return Column(
          children: [
            // 1. LIVE COSMETIC PREVIEW HEADER
            _buildLivePreviewHeader(currentVip),

            SizedBox(height: 16),

            // 2. COSMETICS GRID LIST
            Expanded(
              child: TabBarView(
                controller: _categoryTabController,
                children: _categories.map((category) {
                  final items = _storeItems[category] ?? [];
                  final equipped = _getActiveCustomization(category);

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final String itemId = item['id'] as String;
                      final String name = item['name'] as String;
                      final String desc = item['desc'] as String;
                      final int requiredLevel = item['req'] as int;
                      
                      final bool isLocked = currentVip < requiredLevel;
                      final bool isActive = equipped == itemId;

                      Color itemColor = Colors.grey;
                      if (requiredLevel > 0) {
                        switch (requiredLevel) {
                          case 1: itemColor = Color(0xFF2563EB); break;
                          case 2: itemColor = Color(0xFF8B5CF6); break;
                          case 3: itemColor = Color(0xFFFFD700); break;
                          case 4: itemColor = Color(0xFFE2E8F0); break;
                          case 5: itemColor = Color(0xFF06B6D4); break;
                          case 6: itemColor = Color(0xFFEC4899); break;
                          case 7: itemColor = Color(0xFFD4AF37); break;
                        }
                      }

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isActive ? context.primaryColor.withOpacity(0.06) : context.secondaryBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? itemColor
                                : context.borderColor,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Left indicator (Lock or active frame preview icon)
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isLocked ? Colors.black45 : itemColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isLocked
                                    ? Icon(Icons.lock_outline, color: Colors.white38)
                                    : Text(
                                        requiredLevel > 0 ? 'VIP $requiredLevel' : 'FREE',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: itemColor,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(width: 16),

                             // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    desc,
                                    style: GoogleFonts.poppins(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // CTA button
                            if (isLocked)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Locked',
                                  style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive ? context.borderColor : itemColor,
                                  foregroundColor: isActive ? context.caption : Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isActive ? null : () => _equipItem(category, itemId),
                                child: Text(
                                  isActive ? 'Equipped' : 'Equip',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLivePreviewHeader(int currentVip) {
    // Determine active border level
    int activeFrameLvl = 0;
    final frameId = _vipCtrl.activeFrame.value;
    if (frameId.startsWith('VIP ')) {
      activeFrameLvl = int.tryParse(frameId.substring(4)) ?? 0;
    }

    final nameColorId = _vipCtrl.activeNameColor.value;
    final bubbleId = _vipCtrl.activeChatBubble.value;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: context.smallShadow,
      ),
      child: Column(
        children: [
          Text(
            'LIVE PREVIEW CUSTOMIZER',
            style: GoogleFonts.outfit(
              color: context.caption,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Avatar decorator preview
              Column(
                children: [
                  VipAvatarDecorator(
                    level: activeFrameLvl,
                    size: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Avatar Border',
                    style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 12),
                  ),
                ],
              ),

              // Chat Bubble and Name Glow preview
              Expanded(
                child: Column(
                  children: [
                    // Username glow preview
                    ShaderMask(
                      shaderCallback: (bounds) {
                        if (nameColorId.startsWith('VIP ')) {
                          final lvl = int.tryParse(nameColorId.substring(4)) ?? 0;
                          if (lvl >= 6) {
                            return LinearGradient(
                              colors: [Color(0xFFFF007F), Color(0xFFFFBF00), Color(0xFF00F0FF)],
                            ).createShader(bounds);
                          } else if (lvl == 3) {
                            return LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFD97706)],
                            ).createShader(bounds);
                          } else if (lvl == 5) {
                            return LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
                            ).createShader(bounds);
                          }
                        }
                        return LinearGradient(colors: [context.textPrimary, context.textPrimary]).createShader(bounds);
                      },
                      child: Text(
                        UserProfileCacheManager.currentUser?.username ?? Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'Student',
                        style: GoogleFonts.outfit(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Bubble preview
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: bubbleId.startsWith('VIP ')
                            ? LinearGradient(
                                colors: [
                                  context.primaryColor.withOpacity(0.4),
                                  AppTheme.secondaryColor.withOpacity(0.3),
                                ],
                              )
                            : null,
                        color: bubbleId == 'None' ? context.secondaryBackgroundColor : null,
                        borderRadius: BorderRadius.circular(16),
                        border: bubbleId.startsWith('VIP ')
                            ? Border.all(color: context.accentGold.withOpacity(0.3))
                            : Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        'Hello, this is a premium VIP bubble! 👑',
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
