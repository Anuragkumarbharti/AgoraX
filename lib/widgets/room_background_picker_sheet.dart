import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/room_background_model.dart';
import '../services/room_controller.dart';
import '../services/user_profile_cache_manager.dart';

class RoomBackgroundPickerSheet extends StatefulWidget {
  final RoomBackgroundItem currentBackground;
  final Function(RoomBackgroundItem) onBackgroundSelected;

  const RoomBackgroundPickerSheet({
    Key? key,
    required this.currentBackground,
    required this.onBackgroundSelected,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required RoomBackgroundItem currentBackground,
    required Function(RoomBackgroundItem) onBackgroundSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomBackgroundPickerSheet(
        currentBackground: currentBackground,
        onBackgroundSelected: onBackgroundSelected,
      ),
    );
  }

  @override
  State<RoomBackgroundPickerSheet> createState() =>
      _RoomBackgroundPickerSheetState();
}

class _RoomBackgroundPickerSheetState
    extends State<RoomBackgroundPickerSheet> {
  late String _selectedCategory;
  late RoomBackgroundItem _activeItem;

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'All';
    _activeItem = widget.currentBackground;
  }

  List<RoomBackgroundItem> get _filteredBackgrounds {
    if (_selectedCategory == 'All') {
      return RoomBackgroundCatalog.allBackgrounds;
    }
    if (_selectedCategory == 'VIP') {
      return RoomBackgroundCatalog.allBackgrounds.where((bg) => bg.isVip).toList();
    }
    return RoomBackgroundCatalog.allBackgrounds
        .where((bg) => bg.category.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = MediaQuery.of(context).size.height * 0.72;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wallpaper_rounded,
                        color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Room Backgrounds & FX',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showCustomUploadDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_photo_alternate_rounded,
                                color: Color(0xFFA78BFA), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Custom Upload',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white70, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Categories Horizontal Scroll Bar
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: RoomBackgroundCatalog.categories.length,
              itemBuilder: (context, index) {
                final category = RoomBackgroundCatalog.categories[index];
                final isSelected = category == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                            )
                          : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white12,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Background Grid Items
          Expanded(
            child: _filteredBackgrounds.isEmpty
                ? Center(
                    child: Text(
                      'No backgrounds found in $_selectedCategory',
                      style: GoogleFonts.poppins(color: Colors.white38),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredBackgrounds.length,
                    itemBuilder: (context, index) {
                      final item = _filteredBackgrounds[index];
                      final isSelected = _activeItem.id == item.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeItem = item;
                          });
                          widget.onBackgroundSelected(item);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFD700)
                                  : Colors.white12,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700)
                                          .withOpacity(0.35),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Thumbnail Image / Gradient preview
                                if (item.wallpaperUrl != null &&
                                    item.wallpaperUrl!.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: item.wallpaperUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: item.gradientColors ??
                                              [const Color(0xFF0F172A), const Color(0xFF020617)],
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, err) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: item.gradientColors ??
                                              [const Color(0xFF0F172A), const Color(0xFF020617)],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: item.gradientColors ??
                                            [const Color(0xFF0F172A), const Color(0xFF020617)],
                                        begin: item.gradientBegin,
                                        end: item.gradientEnd,
                                      ),
                                    ),
                                  ),

                                // Dark Scrim for readable title
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.85),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),

                                // Animated FX Badge
                                if (item.type == RoomBackgroundType.animatedBackground)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.85),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.amberAccent,
                                        size: 12,
                                      ),
                                    ),
                                  ),

                                // VIP Tag
                                if (item.isVip)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700),
                                            Color(0xFFFFA000),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'VIP ${item.requiredVipLevel > 0 ? item.requiredVipLevel : ''}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Active Selection Checkmark
                                if (isSelected)
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFD700),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.black,
                                        size: 18,
                                      ),
                                    ),
                                  ),

                                // Title Label
                                Positioned(
                                  bottom: 8,
                                  left: 6,
                                  right: 6,
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Apply Wallpaper',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomUploadDialog(BuildContext context) {
    final TextEditingController urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cloud_upload_rounded, color: Color(0xFFA78BFA)),
            const SizedBox(width: 8),
            Text(
              'Custom Wallpaper',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter image or video URL (WebP, JPG, MP4 recommended 1920x1080):',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://example.com/wallpaper.webp',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                final customItem = RoomBackgroundItem(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  title: 'Custom Upload',
                  category: 'Custom Upload',
                  type: RoomBackgroundType.customUpload,
                  wallpaperUrl: url,
                  gradientColors: const [Color(0xFF0F172A), Color(0xFF020617)],
                  overlayDarkness: 0.25,
                );
                setState(() {
                  _activeItem = customItem;
                });
                widget.onBackgroundSelected(customItem);
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: Text('Apply', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
