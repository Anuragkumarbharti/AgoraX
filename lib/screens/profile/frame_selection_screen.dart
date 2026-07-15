import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';

class FrameSelectionScreen extends StatefulWidget {
  const FrameSelectionScreen({Key? key}) : super(key: key);

  @override
  State<FrameSelectionScreen> createState() => _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends State<FrameSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  String _selectedFrameId = 'golden_crown';
  String _activeCategory = 'All';

  final List<Map<String, dynamic>> _frames = [
    // Free frames
    {
      'id': 'none',
      'name': 'No Frame',
      'desc': 'Clean profile look',
      'category': 'Free',
      'cost': 0,
      'isOwned': true,
      'colors': [Color(0xFF334155), Color(0xFF1E293B)],
      'icon': '⭕',
      'style': FrameStyle.none,
    },
    {
      'id': 'blue_glow',
      'name': 'Blue Glow',
      'desc': 'Soft blue glowing ring',
      'category': 'Free',
      'cost': 0,
      'isOwned': true,
      'colors': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      'icon': '💙',
      'style': FrameStyle.glow,
    },
    // Premium frames
    {
      'id': 'golden_crown',
      'name': 'Golden Crown',
      'desc': 'Royal golden crown with stars',
      'category': 'Premium',
      'cost': 500,
      'isOwned': true,
      'colors': [Color(0xFFFBBF24), Color(0xFFF59E0B)],
      'icon': '👑',
      'style': FrameStyle.crown,
    },
    {
      'id': 'purple_aura',
      'name': 'Purple Aura',
      'desc': 'Mystical purple energy aura',
      'category': 'Premium',
      'cost': 800,
      'isOwned': true,
      'colors': [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      'icon': '🔮',
      'style': FrameStyle.glow,
    },
    {
      'id': 'fire_ring',
      'name': 'Fire Ring',
      'desc': 'Blazing flame ring border',
      'category': 'Premium',
      'cost': 700,
      'isOwned': false,
      'colors': [Color(0xFFF97316), Color(0xFFEF4444)],
      'icon': '🔥',
      'style': FrameStyle.animated,
    },
    {
      'id': 'galaxy',
      'name': 'Galaxy',
      'desc': 'Shimmering galaxy with stars',
      'category': 'Premium',
      'cost': 1200,
      'isOwned': false,
      'colors': [Color(0xFF6366F1), Color(0xFF0EA5E9)],
      'icon': '🌌',
      'style': FrameStyle.animated,
    },
    // VIP frames
    {
      'id': 'diamond_wings',
      'name': 'Diamond Wings',
      'desc': 'Exclusive diamond wings frame for VIP',
      'category': 'VIP',
      'cost': 0,
      'isOwned': false,
      'colors': [Color(0xFF67E8F9), Color(0xFF38BDF8)],
      'icon': '💎',
      'style': FrameStyle.wings,
      'requiresVip': true,
    },
    {
      'id': 'noble_crown',
      'name': 'Noble Crown',
      'desc': 'Ornate noble crown with gems — Noble rank exclusive',
      'category': 'VIP',
      'cost': 0,
      'isOwned': false,
      'colors': [Color(0xFFFBBF24), Color(0xFFEC4899)],
      'icon': '🏅',
      'style': FrameStyle.crown,
      'requiresVip': true,
    },
    // Level-unlock frames
    {
      'id': 'emerald_ring',
      'name': 'Emerald Ring',
      'desc': 'Level 10 unlock — emerald green glow',
      'category': 'Level',
      'cost': 0,
      'isOwned': true,
      'colors': [Color(0xFF10B981), Color(0xFF059669)],
      'icon': '💚',
      'style': FrameStyle.glow,
      'requiresLevel': 10,
    },
    {
      'id': 'rainbow_burst',
      'name': 'Rainbow Burst',
      'desc': 'Level 25 unlock — rainbow animated burst',
      'category': 'Level',
      'cost': 0,
      'isOwned': false,
      'colors': [Color(0xFFF97316), Color(0xFF8B5CF6)],
      'icon': '🌈',
      'style': FrameStyle.animated,
      'requiresLevel': 25,
    },
    {
      'id': 'legendary_aura',
      'name': 'Legendary Aura',
      'desc': 'Level 50 unlock — legendary golden aura',
      'category': 'Level',
      'cost': 0,
      'isOwned': false,
      'colors': [Color(0xFFFBBF24), Color(0xFFF59E0B)],
      'icon': '⭐',
      'style': FrameStyle.animated,
      'requiresLevel': 50,
    },
  ];

  final List<String> _categories = ['All', 'Free', 'Premium', 'VIP', 'Level'];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFrames {
    if (_activeCategory == 'All') return _frames;
    return _frames.where((f) => f['category'] == _activeCategory).toList();
  }

  Map<String, dynamic> get _selectedFrame =>
      _frames.firstWhere((f) => f['id'] == _selectedFrameId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Avatar Frames',
          style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                '✅ Frame Applied!',
                '${_selectedFrame['name']} frame is now active',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: context.primaryColor.withOpacity(0.9),
                colorText: Colors.white,
              );
            },
            child: Text(
              'Apply',
              style: TextStyle(
                  color: context.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPreviewSection(),
          _buildCategoryFilter(),
          Expanded(child: _buildFrameGrid()),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final frame = _selectedFrame;
    final colors = frame['colors'] as List<Color>;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors[0].withOpacity(0.12),
            context.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar preview with selected frame
          AnimatedBuilder(
            animation: _glowController,
            builder: (ctx, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(
                              0.3 + 0.2 * _glowController.value),
                          blurRadius: 20 + 10 * _glowController.value,
                          spreadRadius: 4,
                        )
                      ],
                    ),
                  ),
                  // Frame ring gradient
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          colors[0],
                          colors[1],
                          colors[0],
                          colors[1],
                          colors[0],
                        ],
                      ),
                    ),
                  ),
                  // Dark border
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.scaffoldBackgroundColor,
                    ),
                  ),
                  // Avatar inner
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          context.primaryColor.withOpacity(0.3),
                          AppTheme.secondaryColor.withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Crown/decoration icon on top
                  if (frame['style'] == FrameStyle.crown)
                    Positioned(
                      top: 0,
                      child: Text(
                        frame['icon'] as String,
                        style: TextStyle(fontSize: 26),
                      ),
                    ),
                  // Corner decorations for wings
                  if (frame['style'] == FrameStyle.wings) ...[
                    Positioned(
                      left: 0,
                      child: Text(frame['icon'] as String,
                          style: TextStyle(fontSize: 22)),
                    ),
                    Positioned(
                      right: 0,
                      child: Transform.scale(
                        scaleX: -1,
                        child: Text(frame['icon'] as String,
                            style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                  // Stars for animated frames
                  if (frame['style'] == FrameStyle.animated) ...[
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Transform.rotate(
                        angle: _glowController.value * 6.28,
                        child: Text('✨', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Transform.rotate(
                        angle: -_glowController.value * 6.28,
                        child: Text('✨', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: 16),
          Text(
            frame['name'] as String,
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          Text(
            frame['desc'] as String,
            style: TextStyle(
                color: context.caption, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _categories.map((cat) {
          final isActive = _activeCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? context.primaryColor : context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isActive
                        ? context.primaryColor
                        : context.borderColor),
              ),
              child: Text(cat,
                  style: TextStyle(
                      color:
                          isActive ? Colors.white : context.caption,
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFrameGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _filteredFrames.length,
      itemBuilder: (ctx, i) => _buildFrameItem(_filteredFrames[i]),
    );
  }

  Widget _buildFrameItem(Map<String, dynamic> frame) {
    final isSelected = _selectedFrameId == frame['id'];
    final isOwned = frame['isOwned'] as bool;
    final colors = frame['colors'] as List<Color>;

    return GestureDetector(
      onTap: () {
        if (isOwned) {
          setState(() => _selectedFrameId = frame['id'] as String);
        } else {
          _showPurchaseSheet(frame);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors[0].withOpacity(0.12)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors[0]
                : context.borderColor.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: colors[0].withOpacity(0.3), blurRadius: 8)
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Frame ring preview
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [colors[0], colors[1], colors[0]],
                    ),
                  ),
                ),
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.scaffoldBackgroundColor,
                  ),
                ),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[0].withOpacity(0.15),
                  ),
                  child: Center(
                    child: Text(
                      frame['icon'] as String,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                if (!isOwned)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.45),
                      ),
                      child: Center(
                        child: Icon(Icons.lock_rounded,
                            color: Colors.white70, size: 18),
                      ),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: context.accentOrange,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: context.scaffoldBackgroundColor, width: 2),
                      ),
                      child: Icon(Icons.check,
                          color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              frame['name'] as String,
              style: TextStyle(
                color: isSelected
                    ? colors[0]
                    : context.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            if (frame['cost'] > 0)
              Text(
                isOwned ? '✅ Owned' : '🪙 ${frame['cost']}',
                style: TextStyle(
                  color: isOwned ? context.accentOrange : Color(0xFFFBBF24),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (frame['requiresVip'] == true)
              Text('👑 VIP Only',
                  style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 9,
                      fontWeight: FontWeight.w600))
            else if (frame.containsKey('requiresLevel'))
              Text('🔒 Lv.${frame['requiresLevel']}',
                  style: TextStyle(
                      color: context.caption,
                      fontSize: 9,
                      fontWeight: FontWeight.w600))
            else
              Text('Free',
                  style: TextStyle(
                      color: context.accentOrange,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showPurchaseSheet(Map<String, dynamic> frame) {
    final colors = frame['colors'] as List<Color>;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.secondaryBackgroundColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
            Text(
              frame['icon'] as String,
              style: TextStyle(fontSize: 48),
            ),
            SizedBox(height: 12),
            Text(frame['name'] as String,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(frame['desc'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.caption, fontSize: 13)),
            SizedBox(height: 20),
            if (frame['cost'] > 0) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFBBF24).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Color(0xFFFBBF24).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🪙',
                        style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      '${frame['cost']} Coins',
                      style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors[0],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Get.snackbar(
                      '🎉 Frame Purchased!',
                      '${frame['name']} is now in your collection',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: colors[0].withOpacity(0.9),
                      colorText: Colors.white,
                    );
                  },
                  child: Text('Buy for 🪙${frame['cost']}',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ] else if (frame['requiresVip'] == true)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFBBF24).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text('👑 VIP Exclusive Frame',
                        style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    SizedBox(height: 4),
                    Text(
                        'Upgrade to VIP to unlock this exclusive frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.caption, fontSize: 12)),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.accentOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Reach Level ${frame['requiresLevel']} to unlock this frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.accentOrange, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum FrameStyle { none, glow, crown, wings, animated }
