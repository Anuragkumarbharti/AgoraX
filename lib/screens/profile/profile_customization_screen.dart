import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/vip_controller.dart';
import '../../services/novel_controller.dart';
import '../../services/customization_controller.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/vip_avatar_decorator.dart';
import '../../widgets/novel_badge_widget.dart';
import '../../widgets/novel_avatar_decorator.dart';
import '../../widgets/custom_avatar_frame.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';

class ProfileCustomizationScreen extends StatefulWidget {
  const ProfileCustomizationScreen({Key? key}) : super(key: key);

  @override
  State<ProfileCustomizationScreen> createState() => _ProfileCustomizationScreenState();
}

class _ProfileCustomizationScreenState extends State<ProfileCustomizationScreen> {
  final CustomizationController _custCtrl = Get.find<CustomizationController>();
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();

  // Navigation
  String? _selectedCategory; // null = Main Category List page
  String _activeFilter = 'All'; // All, Owned, Equipped, VIP, Novel, Event, Limited
  String _searchQuery = '';
  final Set<String> _ignoredWarningItems = <String>{};

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Avatar Frame', 'icon': '🖼️', 'desc': 'Animated premium avatar frames'},
    {'name': 'Avatar Background', 'icon': '🌌', 'desc': 'Animated profile backdrops'},
    {'name': 'Entry Effect', 'icon': '⚡', 'desc': 'One-time room entrance effect'},
    {'name': 'Gift Effect', 'icon': '🎁', 'desc': 'Premium animated gifts'},
    {'name': 'Chat Bubble', 'icon': '💬', 'desc': 'Premium chat styling'},
    {'name': 'Badge', 'icon': '🏅', 'desc': 'Profile-only premium badges'},
    {'name': 'Tag Light', 'icon': '🏷️', 'desc': 'Animated tags beside usernames'},
    {'name': 'VIP Membership', 'icon': '💎', 'desc': 'Unlock VIP cosmetics'},
    {'name': 'Novel Membership', 'icon': '📖', 'desc': 'Unlock Novel cosmetics'},
    {'name': 'Community Tag Light', 'icon': '👥', 'desc': 'Owner and moderator tags'},
    {'name': 'Emoji Effects', 'icon': '😊', 'desc': 'Premium animated emoji packs'},
  ];

  // List of all customization items in the system with metadata from controller
  List<Map<String, dynamic>> get _customizationDb => _custCtrl.customizationDb;

  @override
  void initState() {
    super.initState();
    _custCtrl.checkExpirations();
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'Common': return Colors.white60;
      case 'Rare': return Colors.greenAccent;
      case 'Epic': return Colors.blueAccent;
      case 'Legendary': return const Color(0xFFC084FC); // Purple
      case 'Mythic': return const Color(0xFFFBBF24); // Amber
      case 'Limited': return const Color(0xFFEF4444); // Red
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.4),
            radius: 1.4,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF09090B),
            ],
            stops: [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              Expanded(
                child: _selectedCategory == null
                    ? _buildCategoryGrid()
                    : _buildCategoryDetailPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            onPressed: () {
              if (_selectedCategory != null) {
                setState(() {
                  _selectedCategory = null;
                  _activeFilter = 'All';
                  _searchQuery = '';
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedCategory ?? 'Tools',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                _selectedCategory == null
                    ? 'Customize your profile and identity.'
                    : 'Preview, equip, and manage premium tools instantly.',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MAIN SCREEN: CATEGORY SELECTOR GRID ---
  Widget _buildCategoryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        return GestureDetector(
          onTap: () {
            if (cat['name'] == 'VIP') {
              Get.to(() => const VipPurchaseScreen());
            } else if (cat['name'] == 'Novel') {
              Get.to(() => const NovelPurchaseScreen());
            } else {
              setState(() {
                _selectedCategory = cat['name'] as String;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat['icon'] as String,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  cat['name'] as String,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  cat['desc'] as String,
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DETAILS SCREEN: ONE CATEGORY VIEW ---
  Widget _buildCategoryDetailPage() {
    final catName = _selectedCategory!;

    if (catName == 'VIP Membership') {
      Get.to(() => const VipPurchaseScreen());
      return const SizedBox.shrink();
    } else if (catName == 'Novel Membership') {
      Get.to(() => const NovelPurchaseScreen());
      return const SizedBox.shrink();
    }
    
    // special layouts
    if (catName == 'Badge') {
      return _buildBadgesReorderPanel();
    } else if (catName == 'Tag Light' || catName == 'Community Tag Light') {
      return _buildTagsReorderPanel();
    } else if (catName == 'Gift Effect') {
      return _buildGiftsReorderPanel();
    }
 
    // Filter items
    final resolvedCategory = _resolveCategoryKey(catName);
    final dbItems = _customizationDb.where((element) => element['category'] == resolvedCategory).toList();
    
    // Apply Active Filter
    List<Map<String, dynamic>> filteredItems = dbItems;
    if (_activeFilter == 'Owned') {
      filteredItems = dbItems.where((e) => _custCtrl.isItemUnlocked(e['name'])).toList();
    } else if (_activeFilter == 'Equipped') {
      filteredItems = dbItems.where((e) => _isCurrentlyEquipped(catName, e['name'])).toList();
    } else if (_activeFilter == 'VIP') {
      filteredItems = dbItems.where((e) => e['premium'] == 'VIP').toList();
    } else if (_activeFilter == 'Novel') {
      filteredItems = dbItems.where((e) => e['premium'] == 'Novel').toList();
    } else if (_activeFilter == 'Limited') {
      filteredItems = dbItems.where((e) => e['rarity'] == 'Limited').toList();
    }
 
    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((e) => (e['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Insert virtual "None" item at index 0 of the grid view
    final List<Map<String, dynamic>> itemsToShow = [];
    if (_searchQuery.isEmpty) {
      itemsToShow.add({
        'name': 'None',
        'category': resolvedCategory,
        'rarity': 'Common',
        'premium': 'None',
        'req': 'Default styling / No active cosmetic',
        'isVirtualNone': true,
      });
    }
    itemsToShow.addAll(filteredItems);
 
    return Obx(() {
      final previewName = _getPreviewItemName(catName);

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width < 380 ? 1 : width < 620 ? 2 : 3;
          final childAspectRatio = width < 380 ? 1.05 : width < 620 ? 0.78 : 0.86;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildLivePreviewHero(catName, previewName),
              ),
              SliverToBoxAdapter(
                child: _buildSearchAndFiltersRow(),
              ),
              SliverToBoxAdapter(
                child: _buildCategoryWarningReminders(catName),
              ),
              if (itemsToShow.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No customization items found.',
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = itemsToShow[index];
                        return _buildCosmeticCard(item);
                      },
                      childCount: itemsToShow.length,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    });
  }
 
  bool _isCurrentlyEquipped(String category, String itemName) {
    final resolvedCategory = _resolveCategoryKey(category);
    switch (resolvedCategory) {
      case 'Avatar': return _custCtrl.activeAvatar.value == itemName;
      case 'Avatar Frame': return _custCtrl.activeFrame.value == itemName;
      case 'Chat Bubble': return _custCtrl.activeBubble.value == itemName;
      case 'Entry Effect': return _custCtrl.activeEntryEffect.value == itemName;
      case 'Background': return _custCtrl.activeBackground.value == itemName;
      case 'Emoji Pack': return _custCtrl.activeEmojiPack.value == itemName;
      case 'Badges': return _custCtrl.activeBadges.contains(itemName);
      case 'Tags': return _custCtrl.activeTags.contains(itemName);
      case 'Gift Showcase': return _custCtrl.activeGifts.contains(itemName);
      default: return false;
    }
  }

  bool _isAnyItemEquippedInCategory(String category) {
    final resolvedCategory = _resolveCategoryKey(category);
    switch (resolvedCategory) {
      case 'Avatar': return _custCtrl.activeAvatar.value != 'Default';
      case 'Avatar Frame': return _custCtrl.activeFrame.value != 'Normal';
      case 'Chat Bubble': return _custCtrl.activeBubble.value != 'Classic Bubble';
      case 'Entry Effect': return _custCtrl.activeEntryEffect.value != 'None';
      case 'Background': return _custCtrl.activeBackground.value != 'None';
      case 'Emoji Pack': return _custCtrl.activeEmojiPack.value != 'Classic Emojis';
      case 'Badges': return _custCtrl.activeBadges.isNotEmpty;
      case 'Tags': return _custCtrl.activeTags.isNotEmpty;
      case 'Gift Showcase': return _custCtrl.activeGifts.isNotEmpty;
      default: return false;
    }
  }

  String _resolveCategoryKey(String category) {
    switch (category) {
      case 'Avatar Background':
        return 'Background';
      case 'Badge':
        return 'Badges';
      case 'Tag Light':
      case 'Community Tag Light':
        return 'Tags';
      case 'Gift Effect':
        return 'Gift Showcase';
      case 'Emoji Effects':
        return 'Emoji Pack';
      default:
        return category;
    }
  }

  String _getPreviewItemName(String category) {
    final resolvedCategory = _resolveCategoryKey(category);
    switch (resolvedCategory) {
      case 'Avatar Frame':
        return _custCtrl.activeFrame.value;
      case 'Chat Bubble':
        return _custCtrl.activeBubble.value;
      case 'Entry Effect':
        return _custCtrl.activeEntryEffect.value;
      case 'Background':
        return _custCtrl.activeBackground.value;
      case 'Emoji Pack':
        return _custCtrl.activeEmojiPack.value;
      case 'Badges':
        return _custCtrl.activeBadges.isNotEmpty ? _custCtrl.activeBadges.first : 'None';
      case 'Tags':
        return _custCtrl.activeTags.isNotEmpty ? _custCtrl.activeTags.first : 'None';
      case 'Gift Showcase':
        return _custCtrl.activeGifts.isNotEmpty ? _custCtrl.activeGifts.first : 'None';
      default:
        return 'None';
    }
  }

  Widget _buildLivePreviewHero(String category, String previewName) {
    final resolvedCategory = _resolveCategoryKey(category);
    final previewIsEmpty = previewName == 'None';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        final previewBlock = Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8B5CF6).withOpacity(0.25),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Center(
            child: previewIsEmpty
                ? Icon(Icons.auto_awesome_rounded, color: Colors.white.withOpacity(0.25), size: 34)
                : Transform.scale(
                    scale: 1.35,
                    child: _buildItemPreview(resolvedCategory, previewName),
                  ),
          ),
        );

        final previewText = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Live Preview',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFC084FC),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                previewName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preview updates instantly when you equip or change an item.',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10.5),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPreviewPill(category),
                  _buildPreviewPill('Equipped only'),
                ],
              ),
            ],
          ),
        );

        final previewButton = InkWell(
          onTap: previewIsEmpty ? null : () => _triggerPreviewAction(resolvedCategory, previewName, false),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(previewIsEmpty ? 0.04 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_rounded, color: Colors.white70, size: 18),
                const SizedBox(height: 4),
                Text(
                  'Preview',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF151525).withOpacity(0.95),
                const Color(0xFF0F0F16).withOpacity(0.95),
                const Color(0xFF1A1A2A).withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [previewBlock, const SizedBox(width: 14), Expanded(child: previewText)]),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: previewButton),
                  ],
                )
              : Row(
                  children: [
                    previewBlock,
                    const SizedBox(width: 14),
                    previewText,
                    const SizedBox(width: 12),
                    previewButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPreviewPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSearchAndFiltersRow() {
    final filters = ['All', 'Owned', 'Equipped', 'VIP', 'Novel', 'Limited'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final f = filters[index];
              final isSel = _activeFilter == f;
              return GestureDetector(
                onTap: () => setState(() => _activeFilter = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF8B5CF6).withOpacity(0.15) : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Text(
                    f,
                    style: GoogleFonts.poppins(color: isSel ? Colors.white : Colors.white54, fontSize: 11),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryWarningReminders(String catName) {
    final resolvedCategory = _resolveCategoryKey(catName);

    return Obx(() {
      final now = DateTime.now();
      final List<Map<String, String>> warnings = [];

      _custCtrl.itemExpiries.forEach((itemName, expiry) {
        if (_ignoredWarningItems.contains(itemName)) {
          return;
        }
        if (expiry.isAfter(now)) {
          final diff = expiry.difference(now);
          if (diff.inDays <= 3) {
            final item = _customizationDb.firstWhere(
              (element) => element['name'] == itemName,
              orElse: () => <String, dynamic>{},
            );
            if (item.isNotEmpty && item['category'] == resolvedCategory) {
              final premiumType = item['premium'] as String? ?? 'None';
              String message;
              if (diff.inDays >= 1) {
                message = '$itemName expires in ${diff.inDays} days.';
              } else if (diff.inHours >= 1) {
                message = '$itemName expires in ${diff.inHours} hours.';
              } else {
                message = '$itemName expires soon.';
              }
              warnings.add({'name': itemName, 'message': message, 'premium': premiumType});
            }
          }
        }
      });

      if (warnings.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Subscription Renewal Warning',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final warning in warnings) {
                        _ignoredWarningItems.add(warning['name'] ?? '');
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Ignore All'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...warnings.map((warning) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '• ${warning['message']}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openPurchaseFlow(warning['premium'] ?? 'None', warning['name'] ?? ''),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC084FC),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Renew'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _ignoredWarningItems.add(warning['name'] ?? '');
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Ignore'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildCosmeticCard(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final cat = item['category'] as String;
    final isVirtual = item['isVirtualNone'] == true;
    final rarity = item['rarity'] as String;
    final premiumType = item['premium'] as String; // VIP, Novel, None
    final req = item['req'] as String;

    return Obx(() {
      final isOwned = isVirtual ? true : _custCtrl.isItemUnlocked(name);
      final expiry = _custCtrl.itemExpiries[name];
      final now = DateTime.now();
      final bool hasExpiry = expiry != null;
      final bool isExpired = hasExpiry && expiry.isBefore(now);
      final int remainingDays = hasExpiry ? expiry.difference(now).inDays : 999;
      
      final bool showEquipUnequip = isVirtual || !hasExpiry || !isExpired;
      final bool showRenewal = !isVirtual && (hasExpiry && (isExpired || remainingDays <= 3));

      final isEquipped = isVirtual 
          ? !_isAnyItemEquippedInCategory(cat)
          : _isCurrentlyEquipped(cat, name);
      final isFav = isVirtual ? false : _custCtrl.favorites.contains(name);
      final rColor = _getRarityColor(rarity);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleCardPrimaryAction(
          category: cat,
          name: name,
          premiumType: premiumType,
          isVirtual: isVirtual,
          isOwned: isOwned,
          isEquipped: isEquipped,
          showRenewal: showRenewal,
        ),
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEquipped ? const Color(0xFF10B981) : Colors.white.withOpacity(0.04),
            width: isEquipped ? 2.0 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // 1. Large Preview Container
                Expanded(
                  child: GestureDetector(
                    onTap: () => _triggerPreviewAction(cat, name, isVirtual),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            isVirtual 
                                ? const Icon(Icons.block_rounded, size: 36, color: Colors.white30)
                                : _buildItemPreview(cat, name),
                            // Quick "👁 Preview" overlay badge
                            Positioned(
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.visibility_rounded, size: 10, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text('Preview', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 8)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Info area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: rColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rarity.toUpperCase(),
                          style: GoogleFonts.poppins(color: rColor, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Action Buttons (✅ Equip / ❌ Unequip / Buy / Renew)
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: Row(
                      children: [
                        if (showEquipUnequip)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEquipped ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _handleCardPrimaryAction(
                                category: cat,
                                name: name,
                                premiumType: premiumType,
                                isVirtual: isVirtual,
                                isOwned: isOwned,
                                isEquipped: isEquipped,
                                showRenewal: showRenewal,
                              ),
                              child: Text(
                                isEquipped 
                                    ? (isVirtual ? 'Default' : '❌ Unequip')
                                    : '✅ Equip',
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        if (showEquipUnequip && showRenewal) const SizedBox(width: 6),
                        if (showRenewal)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _openPurchaseFlow(premiumType, name),
                              child: Text(
                                isExpired ? 'Buy Again' : 'Renew',
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        if (!isVirtual && !isOwned && !showRenewal)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.lock_rounded, size: 10, color: Colors.white24),
                              label: Text(
                                'Locked',
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.01),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _openPurchaseFlow(premiumType, name),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Premium Ribbon (VIP or Novel)
            if (!isVirtual && premiumType != 'None')
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: premiumType == 'Novel' ? const Color(0xFFF97316) : const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    premiumType,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Favorite star & Details info icons
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isVirtual)
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: Colors.white30, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _triggerDetailsAction(name, req, premiumType, isVirtual),
                    ),
                  const SizedBox(width: 4),
                  if (!isVirtual)
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFav ? const Color(0xFFFFD700) : Colors.white30,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _custCtrl.toggleFavorite(name),
                    ),
                ],
              ),
            ),

            // Blur lock overlay
            if (!isOwned)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                    child: Container(
                      color: Colors.black.withOpacity(0.12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  });
}

  void _handleCardPrimaryAction({
    required String category,
    required String name,
    required String premiumType,
    required bool isVirtual,
    required bool isOwned,
    required bool isEquipped,
    required bool showRenewal,
  }) {
    if (isVirtual) {
      _custCtrl.removeItem(category);
      return;
    }

    if (showRenewal) {
      _openPurchaseFlow(premiumType, name);
      return;
    }

    if (!isOwned) {
      if (premiumType == 'VIP' || premiumType == 'Novel') {
        _openPurchaseFlow(premiumType, name);
      } else {
        _custCtrl.unlockItem(name).then((_) => _custCtrl.equipItem(category, name));
      }
      return;
    }

    if (isEquipped) {
      _custCtrl.removeItem(category);
    } else {
      _custCtrl.equipItem(category, name);
    }
  }

  void _openPurchaseFlow(String premiumType, String itemName) {
    if (premiumType == 'VIP') {
      Get.to(() => const VipPurchaseScreen());
      return;
    }
    if (premiumType == 'Novel') {
      Get.to(() => const NovelPurchaseScreen());
      return;
    }

    if (itemName.isNotEmpty) {
      _custCtrl.unlockItem(itemName).then((_) => Get.snackbar(
        'Unlocked',
        '$itemName is now available.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        colorText: Colors.white,
      ));
    }
  }

  void _triggerPreviewAction(String category, String name, bool isVirtual) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF151518),
        title: Text(isVirtual ? '⭕ None (Default Preview)' : '👁️ Preview: $name', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              alignment: Alignment.center,
              child: isVirtual 
                  ? const Icon(Icons.block_rounded, size: 60, color: Colors.white24)
                  : Transform.scale(scale: 1.5, child: _buildItemPreview(category, name)),
            ),
            const SizedBox(height: 16),
            Text(
              isVirtual 
                  ? 'Reverts the profile layout back to the standard look.'
                  : 'This visual perk will be applied to your profile once equipped.',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  void _triggerDetailsAction(String name, String req, String premiumType, bool isVirtual) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1F1F23),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text('ℹ️ Cosmetic Details', style: GoogleFonts.outfit(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name:', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Requirements:', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(isVirtual ? 'Available for all users by default.' : req, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            Text('Tier / Source:', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(premiumType == 'None' ? 'Free / Event' : '$premiumType Exclusive Customization', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Unlock Target'),
            onPressed: () {
              Get.back();
              if (!isVirtual) {
                if (premiumType == 'VIP') {
                  Get.to(() => const VipPurchaseScreen());
                } else if (premiumType == 'Novel') {
                  Get.to(() => const NovelPurchaseScreen());
                } else {
                  _custCtrl.unlockItem(name);
                  Get.snackbar('Unlocked!', '$name is now unlocked.');
                }
              }
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPreview(String category, String name) {
    switch (category) {
      case 'Avatar':
        final defaultUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400';
        final url = _custCtrl.getAvatarUrl(name, defaultUrl);
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: url.startsWith('http')
                  ? NetworkImage(url) as ImageProvider
                  : FileImage(File(url)) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );

      case 'Avatar Frame':
        final childWidget = const Icon(Icons.person, color: Colors.white30, size: 24);
        if (name == 'Royal Frame') {
          return VipAvatarDecorator(level: 1, size: 50, child: childWidget);
        } else if (name.contains('Neon Frame')) {
          return VipAvatarDecorator(level: 2, size: 50, child: childWidget);
        } else if (name.contains('Gold Glow Frame')) {
          return VipAvatarDecorator(level: 3, size: 50, child: childWidget);
        } else if (name.contains('Diamond Frame')) {
          return VipAvatarDecorator(level: 4, size: 50, child: childWidget);
        } else if (name.contains('Crystal Cyan Frame')) {
          return VipAvatarDecorator(level: 5, size: 50, child: childWidget);
        } else if (name.contains('Rainbow Frame')) {
          return VipAvatarDecorator(level: 6, size: 50, child: childWidget);
        } else if (name.contains('Royal Crown')) {
          return VipAvatarDecorator(level: 7, size: 50, child: childWidget);
        } else if (name.contains('Galaxy Orbit')) {
          return NovelAvatarDecorator(level: 2, size: 50, child: childWidget);
        } else if (name.contains('Royal Gold Palace')) {
          return NovelAvatarDecorator(level: 3, size: 50, child: childWidget);
        } else if (name.contains('Dragon Fire Frame') || name.contains('Dragon Frame')) {
          return NovelAvatarDecorator(level: 4, size: 50, child: childWidget);
        } else if (name.contains('Phoenix Flame')) {
          return NovelAvatarDecorator(level: 5, size: 50, child: childWidget);
        } else if (name.contains('Celestial Sky Frame') || name.contains('Celestial Sky')) {
          return NovelAvatarDecorator(level: 6, size: 50, child: childWidget);
        } else if (name.contains('Cosmic Emperor') || name.contains('Immortal Frame')) {
          return NovelAvatarDecorator(level: 7, size: 50, child: childWidget);
        }
        return const Icon(Icons.portrait_rounded, size: 48, color: Colors.white30);

      case 'Chat Bubble':
        return Container(
          width: 50,
          height: 30,
          decoration: BoxDecoration(
            color: name.contains('VIP')
                ? const Color(0xFFFFD700).withOpacity(0.2)
                : name.contains('Neon')
                    ? const Color(0xFF06B6D4).withOpacity(0.2)
                    : name.contains('Love')
                        ? const Color(0xFFEC4899).withOpacity(0.2)
                        : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          alignment: Alignment.center,
          child: const Text('Msg', style: TextStyle(color: Colors.white38, fontSize: 9)),
        );

      case 'Entry Effect':
        return const Text('⚡', style: TextStyle(fontSize: 28));
      case 'Entry Animation':
        return const Text('🎬', style: TextStyle(fontSize: 28));
      case 'Avatar Effect':
        return const Text('✨', style: TextStyle(fontSize: 28));
      case 'Name Effect':
        return const Text('🎨', style: TextStyle(fontSize: 28));
      case 'Profile Theme':
        return const Text('🌈', style: TextStyle(fontSize: 28));
      case 'Background':
        return const Text('🖼️', style: TextStyle(fontSize: 28));
      case 'Badges':
        return const Text('🏅', style: TextStyle(fontSize: 28));
      case 'Tags':
        return const Text('🏷️', style: TextStyle(fontSize: 28));
      case 'Emoji Pack':
        return const Text('😊', style: TextStyle(fontSize: 28));
      case 'Gift Showcase':
        return const Text('🎁', style: TextStyle(fontSize: 28));
      default:
        return const Icon(Icons.dashboard_customize_outlined, size: 36, color: Colors.white24);
    }
  }

  // --- SPECIAL SCREEN: BADGES LIST REORDERING ---
  Widget _buildBadgesReorderPanel() {
    final allBadges = _customizationDb.where((e) => e['category'] == 'Badges').toList();

    return Obx(() {
      final activeList = _custCtrl.activeBadges.toList();

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Badges Row showing Max 5 Ordering
              Text(
                'ACTIVE BADGE ORDER (DRAG TO SORT - MAX 5)',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              Container(
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: activeList.isEmpty
                    ? Center(
                        child: Text(
                          'No active badges. Equip badges below.',
                          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                        ),
                      )
                    : ReorderableListView(
                        physics: const ClampingScrollPhysics(),
                        children: List.generate(activeList.length, (index) {
                          final bName = activeList[index];
                          final dbBadge = allBadges.firstWhere((e) => e['name'] == bName, orElse: () => allBadges[0]);
                          final rColor = _getRarityColor(dbBadge['rarity']);
                          return ListTile(
                            key: ValueKey('active_badge_$bName'),
                            leading: const Icon(Icons.drag_handle_rounded, color: Colors.white30),
                            title: Row(
                              children: [
                                Text(dbBadge['name'] as String, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(
                                  (dbBadge['rarity'] as String).toUpperCase(),
                                  style: GoogleFonts.poppins(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => _custCtrl.toggleBadge(bName),
                            ),
                          );
                        }),
                        onReorder: (oldIndex, newIndex) {
                          _custCtrl.reorderBadges(oldIndex, newIndex);
                        },
                      ),
              ),
              const SizedBox(height: 24),

              // Available Unlocked Badges list
              Text(
                'AVAILABLE BADGES',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allBadges.length,
                itemBuilder: (context, index) {
                  final b = allBadges[index];
                  final name = b['name'] as String;
                  final isUnlocked = _custCtrl.unlockedItems.contains(name);
                  final isEquipped = activeList.contains(name);
                  final rColor = _getRarityColor(b['rarity']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEquipped ? const Color(0xFF10B981) : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🏅', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              (b['rarity'] as String).toUpperCase(),
                              style: GoogleFonts.poppins(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (isUnlocked)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEquipped ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _custCtrl.toggleBadge(name),
                            child: Text(
                              isEquipped ? 'Remove' : 'Equip',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        else ElevatedButton.icon(
                            icon: const Icon(Icons.lock_rounded, size: 10, color: Colors.white24),
                            label: Text('Locked', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white24)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.01),
                            ),
                            onPressed: () {
                              Get.snackbar('Locked Badge', b['req'] as String);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  // --- SPECIAL SCREEN: TAGS LIST REORDERING ---
  Widget _buildTagsReorderPanel() {
    final allTags = _customizationDb.where((e) => e['category'] == 'Tags').toList();

    return Obx(() {
      final activeList = _custCtrl.activeTags.toList();

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Tags Row showing Max 3 Ordering
              Text(
                'ACTIVE TAG LIGHT ORDER (DRAG TO SORT - MAX 5)',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: activeList.isEmpty
                    ? Center(
                        child: Text(
                          'No active tag lights. Equip tag lights below.',
                          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                        ),
                      )
                    : ReorderableListView(
                        physics: const ClampingScrollPhysics(),
                        children: List.generate(activeList.length, (index) {
                          final tagName = activeList[index];
                          final dbTag = allTags.firstWhere((e) => e['name'] == tagName, orElse: () => allTags[0]);
                          final rColor = _getRarityColor(dbTag['rarity']);
                          return ListTile(
                            key: ValueKey('active_tag_$tagName'),
                            leading: const Icon(Icons.drag_handle_rounded, color: Colors.white30),
                            title: Row(
                              children: [
                                Text(dbTag['name'] as String, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(
                                  (dbTag['rarity'] as String).toUpperCase(),
                                  style: GoogleFonts.poppins(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => _custCtrl.toggleTag(tagName),
                            ),
                          );
                        }),
                        onReorder: (oldIndex, newIndex) {
                          _custCtrl.reorderTags(oldIndex, newIndex);
                        },
                      ),
              ),
              const SizedBox(height: 24),

              // Available Unlocked Tags list
              Text(
                'AVAILABLE TAG LIGHTS',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allTags.length,
                itemBuilder: (context, index) {
                  final t = allTags[index];
                  final name = t['name'] as String;
                  final isUnlocked = _custCtrl.isItemUnlocked(name);
                  final isEquipped = activeList.contains(name);
                  final rColor = _getRarityColor(t['rarity']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEquipped ? const Color(0xFF10B981) : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🏷️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              (t['rarity'] as String).toUpperCase(),
                              style: GoogleFonts.poppins(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (isUnlocked)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEquipped ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _custCtrl.toggleTag(name),
                            child: Text(
                              isEquipped ? '❌ Hide' : '✅ Equip',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        else ElevatedButton.icon(
                            icon: const Icon(Icons.lock_rounded, size: 10, color: Colors.white24),
                            label: Text('Locked', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white24)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.01),
                            ),
                            onPressed: () {
                              Get.snackbar('Locked Tag', t['req'] as String);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  // --- SPECIAL SCREEN: GIFT SHOWCASE REORDERING ---
  Widget _buildGiftsReorderPanel() {
    final allGifts = _customizationDb.where((e) => e['category'] == 'Gift Showcase').toList();

    return Obx(() {
      final activeList = _custCtrl.activeGifts.toList();

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Gifts Showcase Row showing Max 3 Ordering
              Text(
                'ACTIVE GIFT EFFECT ORDER (DRAG TO SORT - MAX 3)',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: activeList.isEmpty
                    ? Center(
                        child: Text(
                          'Gift effect stack is empty. Equip gift effects below.',
                          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                        ),
                      )
                    : ReorderableListView(
                        physics: const ClampingScrollPhysics(),
                        children: List.generate(activeList.length, (index) {
                          final giftName = activeList[index];
                          final dbGift = allGifts.firstWhere((e) => e['name'] == giftName, orElse: () => allGifts[0]);
                          final rColor = _getRarityColor(dbGift['rarity']);
                          return ListTile(
                            key: ValueKey('active_gift_$giftName'),
                            leading: const Icon(Icons.drag_handle_rounded, color: Colors.white30),
                            title: Row(
                              children: [
                                Text(dbGift['name'] as String, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(
                                  (dbGift['rarity'] as String).toUpperCase(),
                                  style: GoogleFonts.poppins(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => _custCtrl.toggleGift(giftName),
                            ),
                          );
                        }),
                        onReorder: (oldIndex, newIndex) {
                          _custCtrl.reorderGifts(oldIndex, newIndex);
                        },
                      ),
              ),
              const SizedBox(height: 24),

              // Available Unlocked Gifts list
              Text(
                'AVAILABLE GIFT EFFECTS',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allGifts.length,
                itemBuilder: (context, index) {
                  final g = allGifts[index];
                  final name = g['name'] as String;
                  final isUnlocked = _custCtrl.isItemUnlocked(name);
                  final isEquipped = activeList.contains(name);
                  final rColor = _getRarityColor(g['rarity']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEquipped ? const Color(0xFF10B981) : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              (g['rarity'] as String).toUpperCase(),
                              style: GoogleFonts.poppins(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (isUnlocked)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEquipped ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _custCtrl.toggleGift(name),
                            child: Text(
                              isEquipped ? '❌ Hide' : '✅ Equip',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        else ElevatedButton.icon(
                            icon: const Icon(Icons.lock_rounded, size: 10, color: Colors.white24),
                            label: Text('Locked', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white24)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.01),
                            ),
                            onPressed: () {
                              Get.snackbar('Locked Gift', g['req'] as String);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
