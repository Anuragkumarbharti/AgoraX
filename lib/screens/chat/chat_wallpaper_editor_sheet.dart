import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../services/chat/chat_wallpaper_service.dart';

class ChatWallpaperEditorSheet extends StatefulWidget {
  final String conversationId;

  const ChatWallpaperEditorSheet({
    Key? key,
    required this.conversationId,
  }) : super(key: key);

  @override
  State<ChatWallpaperEditorSheet> createState() => _ChatWallpaperEditorSheetState();
}

class _ChatWallpaperEditorSheetState extends State<ChatWallpaperEditorSheet> {
  late WallpaperType _type;
  late String _value;
  late double _dimness;
  late double _blur;
  late String _fitMode;

  @override
  void initState() {
    super.initState();
    final current = ChatWallpaperService.to.getWallpaper(widget.conversationId);
    _type = current.type;
    _value = current.value;
    _dimness = current.dimness;
    _blur = current.blur;
    _fitMode = current.fitMode;
  }

  Future<void> _pickImage(ImageSource source) async {
    final path = await ChatWallpaperService.to.pickCustomWallpaperImage(source);
    if (path != null && path.isNotEmpty) {
      setState(() {
        _type = WallpaperType.customImage;
        _value = path;
      });
    }
  }

  BoxFit _parseBoxFit(String mode) {
    switch (mode) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  Widget _buildWallpaperBackground() {
    Widget baseWidget;

    if (_type == WallpaperType.customImage && File(_value).existsSync()) {
      baseWidget = Image.file(
        File(_value),
        fit: _parseBoxFit(_fitMode),
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_type == WallpaperType.solidColor) {
      Color c = const Color(0xFF0F172A);
      try {
        final hexStr = _value.replaceAll('#', '');
        c = Color(int.parse('FF$hexStr', radix: 16));
      } catch (_) {}
      baseWidget = Container(color: c);
    } else {
      final preset = ChatWallpaperService.presets.firstWhereOrNull((x) => x['id'] == _value) ??
          ChatWallpaperService.presets.first;
      final List<Color> colors = List<Color>.from(preset['colors']);
      baseWidget = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        baseWidget,
        if (_blur > 0)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
            child: Container(color: Colors.transparent),
          ),
        Container(
          color: Colors.black.withOpacity(_dimness),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chat Wallpaper Controls',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await ChatWallpaperService.to.resetWallpaper(widget.conversationId);
                    Get.back();
                    Get.snackbar(
                      'Reset',
                      'Wallpaper reset to default dark',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: context.primaryColor,
                      colorText: Colors.white,
                    );
                  },
                  child: Text('Reset', style: GoogleFonts.outfit(color: context.warningColor)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── LIVE CHAT PREVIEW CONTAINER ───
                    Text(
                      'Live Chat Readability Preview',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 170,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          _buildWallpaperBackground(),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Incoming message
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Hey! How does this wallpaper look? 👋',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF1E293B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Outgoing message
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: context.primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Looks super readable and clean! ✨',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── CHOOSE IMAGE FROM GALLERY OR CAMERA ───
                    Text(
                      'Choose Custom Wallpaper',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.primaryColor.withOpacity(0.15),
                              foregroundColor: context.primaryColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: context.primaryColor.withOpacity(0.4)),
                              ),
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 20),
                            label: Text('Gallery Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.primaryColor.withOpacity(0.15),
                              foregroundColor: context.primaryColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: context.primaryColor.withOpacity(0.4)),
                              ),
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 20),
                            label: Text('Take Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── CONTROLS: DIMNESS OPACITY ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Background Dimness (Opacity)',
                          style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(_dimness * 100).round()}%',
                          style: GoogleFonts.outfit(color: context.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: _dimness,
                      min: 0.0,
                      max: 0.8,
                      divisions: 16,
                      activeColor: context.primaryColor,
                      inactiveColor: context.borderColor,
                      onChanged: (v) => setState(() => _dimness = v),
                    ),

                    // ─── CONTROLS: BLUR RADIUS ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Background Blur Radius',
                          style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${_blur.round()} px',
                          style: GoogleFonts.outfit(color: context.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: _blur,
                      min: 0.0,
                      max: 20.0,
                      divisions: 20,
                      activeColor: context.primaryColor,
                      inactiveColor: context.borderColor,
                      onChanged: (v) => setState(() => _blur = v),
                    ),

                    if (_type == WallpaperType.customImage) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Image Fit Mode', style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.w600)),
                          DropdownButton<String>(
                            value: _fitMode,
                            dropdownColor: context.secondaryBackgroundColor,
                            style: GoogleFonts.outfit(color: context.primaryColor, fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(value: 'cover', child: Text('Cover (Fill)')),
                              DropdownMenuItem(value: 'contain', child: Text('Contain (Fit)')),
                              DropdownMenuItem(value: 'fill', child: Text('Stretch')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _fitMode = val);
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      'Preset Wallpapers',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: ChatWallpaperService.presets.length,
                        itemBuilder: (context, idx) {
                          final p = ChatWallpaperService.presets[idx];
                          final isSel = _type == WallpaperType.preset && _value == p['id'];
                          final List<Color> colors = List<Color>.from(p['colors']);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _type = WallpaperType.preset;
                                _value = p['id'];
                              });
                            },
                            child: Container(
                              width: 65,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(colors: colors),
                                border: Border.all(
                                  color: isSel ? context.primaryColor : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  p['icon'] as IconData,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 22,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Solid Color Wallpapers',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: ChatWallpaperService.solidColors.length,
                        itemBuilder: (context, idx) {
                          final sc = ChatWallpaperService.solidColors[idx];
                          final isSel = _type == WallpaperType.solidColor && _value == sc['hex'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _type = WallpaperType.solidColor;
                                _value = sc['hex'];
                              });
                            },
                            child: Container(
                              width: 45,
                              height: 45,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sc['color'] as Color,
                                border: Border.all(
                                  color: isSel ? context.primaryColor : context.borderColor,
                                  width: isSel ? 3.0 : 1.0,
                                ),
                              ),
                              child: isSel ? Icon(Icons.check, color: context.primaryColor, size: 20) : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ─── SAVE BUTTON ───
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: () async {
                  final wp = ChatWallpaper(
                    conversationId: widget.conversationId,
                    type: _type,
                    value: _value,
                    dimness: _dimness,
                    blur: _blur,
                    fitMode: _fitMode,
                  );
                  await ChatWallpaperService.to.saveWallpaper(wp);
                  Get.back();
                  Get.snackbar(
                    'Wallpaper Saved',
                    'Chat background updated successfully!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: context.primaryColor,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                },
                child: Text(
                  'Apply Wallpaper',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
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
}
