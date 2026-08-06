import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class CustomImageEditor extends StatefulWidget {
  final File imageFile;

  const CustomImageEditor({Key? key, required this.imageFile}) : super(key: key);

  /// Helper method to launch the editor and get the result
  static Future<File?> editImage(BuildContext context, File file) async {
    return Navigator.of(context).push<File?>(
      MaterialPageRoute(
        builder: (context) => CustomImageEditor(imageFile: file),
      ),
    );
  }

  @override
  State<CustomImageEditor> createState() => _CustomImageEditorState();
}

enum CropRatio {
  free,
  ratio1_1,
  ratio4_5,
  ratio16_9,
  circle,
}

class EditorState {
  final double scale;
  final Offset position;
  final double rotation; // in radians
  final bool flipX;
  final bool flipY;
  final double brightness; // -1.0 to 1.0
  final double contrast;   // 0.5 to 1.5
  final double saturation; // 0.0 to 2.0
  final CropRatio ratio;

  EditorState({
    required this.scale,
    required this.position,
    required this.rotation,
    required this.flipX,
    required this.flipY,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.ratio,
  });

  EditorState copyWith({
    double? scale,
    Offset? position,
    double? rotation,
    bool? flipX,
    bool? flipY,
    double? brightness,
    double? contrast,
    double? saturation,
    CropRatio? ratio,
  }) {
    return EditorState(
      scale: scale ?? this.scale,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      ratio: ratio ?? this.ratio,
    );
  }
}

class _CustomImageEditorState extends State<CustomImageEditor> {
  // Image metadata
  ui.Image? _uiImage;
  bool _loading = true;

  // History for Undo
  final List<EditorState> _history = [];
  
  // Current values
  double _scale = 1.0;
  Offset _position = Offset.zero;
  double _rotation = 0.0;
  bool _flipX = false;
  bool _flipY = false;
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  CropRatio _ratio = CropRatio.free;

  // Gestures
  double _baseScale = 1.0;
  Offset _basePosition = Offset.zero;

  // Tab controller for adjustments vs crop
  int _activeTab = 0; // 0 = Crop/Transform, 1 = Adjustments

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _uiImage = frame.image;
        _loading = false;
      });
      _saveHistory();
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _saveHistory() {
    if (_history.length > 50) _history.removeAt(0);
    _history.add(EditorState(
      scale: _scale,
      position: _position,
      rotation: _rotation,
      flipX: _flipX,
      flipY: _flipY,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      ratio: _ratio,
    ));
  }

  void _undo() {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast(); // Remove current state
        final prev = _history.last;
        _scale = prev.scale;
        _position = prev.position;
        _rotation = prev.rotation;
        _flipX = prev.flipX;
        _flipY = prev.flipY;
        _brightness = prev.brightness;
        _contrast = prev.contrast;
        _saturation = prev.saturation;
        _ratio = prev.ratio;
      });
    }
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _position = Offset.zero;
      _rotation = 0.0;
      _flipX = false;
      _flipY = false;
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _ratio = CropRatio.free;
      _saveHistory();
    });
  }

  List<double> _getColorMatrix() {
    final double t = (1.0 - _contrast) / 2.0;
    List<double> matrix = [
      _contrast, 0, 0, 0, t * 255 + _brightness * 255,
      0, _contrast, 0, 0, t * 255 + _brightness * 255,
      0, 0, _contrast, 0, t * 255 + _brightness * 255,
      0, 0, 0, 1, 0,
    ];

    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;
    
    final double invSat = 1.0 - _saturation;
    final double rR = lr * invSat + _saturation;
    final double rG = lg * invSat;
    final double rB = lb * invSat;
    
    final double gR = lr * invSat;
    final double gG = lg * invSat + _saturation;
    final double gB = lb * invSat;
    
    final double bR = lr * invSat;
    final double bG = lg * invSat;
    final double bB = lb * invSat + _saturation;

    return [
      matrix[0] * rR + matrix[1] * gR + matrix[2] * bR,
      matrix[0] * rG + matrix[1] * gG + matrix[2] * bG,
      matrix[0] * rB + matrix[1] * gB + matrix[2] * bB,
      0,
      matrix[4],

      matrix[5] * rR + matrix[6] * gR + matrix[7] * bR,
      matrix[5] * rG + matrix[6] * gG + matrix[7] * bG,
      matrix[5] * rB + matrix[6] * gB + matrix[7] * bB,
      0,
      matrix[9],

      matrix[10] * rR + matrix[11] * gR + matrix[12] * bR,
      matrix[10] * rG + matrix[11] * gG + matrix[12] * bG,
      matrix[10] * rB + matrix[11] * gB + matrix[12] * bB,
      0,
      matrix[14],

      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _applyAndSave() async {
    if (_uiImage == null) return;
    setState(() => _loading = true);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Determine output sizes based on aspect ratio
      double outW = _uiImage!.width.toDouble();
      double outH = _uiImage!.height.toDouble();

      switch (_ratio) {
        case CropRatio.ratio1_1:
          final minSize = math.min(outW, outH);
          outW = minSize;
          outH = minSize;
          break;
        case CropRatio.ratio4_5:
          if (outW / outH > 0.8) {
            outW = outH * 0.8;
          } else {
            outH = outW / 0.8;
          }
          break;
        case CropRatio.ratio16_9:
          if (outW / outH > 1.7777) {
            outW = outH * 1.7777;
          } else {
            outH = outW / 1.7777;
          }
          break;
        case CropRatio.circle:
          final minSize = math.min(outW, outH);
          outW = minSize;
          outH = minSize;
          break;
        case CropRatio.free:
          break;
      }

      // 1. Draw a background color (if transparent)
      final bgPaint = ui.Paint()..color = Colors.black;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, outW, outH), bgPaint);

      // 2. Setup clipping if circle crop
      if (_ratio == CropRatio.circle) {
        canvas.clipPath(
          ui.Path()..addOval(ui.Rect.fromLTWH(0, 0, outW, outH)),
        );
      }

      // 3. Transform canvas centered on the image
      canvas.translate(outW / 2, outH / 2);

      // Adjust for flips
      canvas.scale(_flipX ? -1.0 : 1.0, _flipY ? -1.0 : 1.0);

      // Adjust for rotation
      canvas.rotate(_rotation);

      // Adjust scale and translation
      canvas.scale(_scale);
      canvas.translate(_position.dx, _position.dy);

      // 4. Paint with color matrix adjustments
      final paint = ui.Paint()
        ..colorFilter = ui.ColorFilter.matrix(_getColorMatrix());

      canvas.drawImageRect(
        _uiImage!,
        ui.Rect.fromLTWH(0, 0, _uiImage!.width.toDouble(), _uiImage!.height.toDouble()),
        ui.Rect.fromLTWH(
          -_uiImage!.width / 2,
          -_uiImage!.height / 2,
          _uiImage!.width.toDouble(),
          _uiImage!.height.toDouble(),
        ),
        paint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(outW.round(), outH.round());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      // Automatically compress and write to a temporary file
      final tempDir = await getTemporaryDirectory();
      final editedFile = File('${tempDir.path}/IMG_EDIT_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await editedFile.writeAsBytes(buffer);

      setState(() => _loading = false);
      if (mounted) {
        Navigator.of(context).pop(editedFile);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'IMAGE EDITOR',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _reset,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ElevatedButton(
              onPressed: _loading ? null : _applyAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5865F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                'Apply',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5865F2)))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ClipRect(
                        child: GestureDetector(
                          onScaleStart: (details) {
                            _baseScale = _scale;
                            _basePosition = _position - details.localFocalPoint / _scale;
                          },
                          onScaleUpdate: (details) {
                            setState(() {
                              _scale = (_baseScale * details.scale).clamp(0.5, 5.0);
                              _position = details.localFocalPoint + _basePosition * _scale;
                            });
                          },
                          onScaleEnd: (_) => _saveHistory(),
                          child: AspectRatio(
                            aspectRatio: _getAspectRatioValue(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: _ratio == CropRatio.circle ? BorderRadius.circular(999) : BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: ClipPath(
                                clipper: _ratio == CropRatio.circle ? _CircleClipper() : null,
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.matrix(_getColorMatrix()),
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..translate(_position.dx, _position.dy)
                                      ..scale(_flipX ? -_scale : _scale, _flipY ? -_scale : _scale)
                                      ..rotateZ(_rotation),
                                    child: _uiImage != null
                                        ? RawImage(image: _uiImage, fit: BoxFit.contain)
                                        : const SizedBox(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildControlPanel(),
              ],
            ),
    );
  }

  double _getAspectRatioValue() {
    switch (_ratio) {
      case CropRatio.ratio1_1:
      case CropRatio.circle:
        return 1.0;
      case CropRatio.ratio4_5:
        return 4.0 / 5.0;
      case CropRatio.ratio16_9:
        return 16.0 / 9.0;
      case CropRatio.free:
      default:
        if (_uiImage != null) {
          return _uiImage!.width / _uiImage!.height;
        }
        return 1.0;
    }
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF11131C),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTabHeader(0, 'Transform', Icons.crop_rotate),
              const SizedBox(width: 32),
              _buildTabHeader(1, 'Adjustments', Icons.tune),
            ],
          ),
          const SizedBox(height: 16),
          if (_activeTab == 0) _buildTransformPanel(),
          if (_activeTab == 1) _buildAdjustmentsPanel(),
        ],
      ),
    );
  }

  Widget _buildTabHeader(int tabIndex, String title, IconData icon) {
    final active = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabIndex),
      child: Column(
        children: [
          Icon(icon, color: active ? const Color(0xFF5865F2) : Colors.white38, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: active ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTransformPanel() {
    return Column(
      children: [
        // Ratios Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildRatioButton(CropRatio.free, 'Freeform'),
                _buildRatioButton(CropRatio.ratio1_1, '1:1'),
                _buildRatioButton(CropRatio.ratio4_5, '4:5'),
                _buildRatioButton(CropRatio.ratio16_9, '16:9'),
                _buildRatioButton(CropRatio.circle, 'Circle'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _rotation += math.pi / 2;
                  _saveHistory();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _flipX = !_flipX;
                  _saveHistory();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _flipY = !_flipY;
                  _saveHistory();
                });
              },
            ),
          ],
        )
      ],
    );
  }

  Widget _buildRatioButton(CropRatio ratio, String label) {
    final selected = _ratio == ratio;
    return GestureDetector(
      onTap: () {
        setState(() {
          _ratio = ratio;
          _saveHistory();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5865F2).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF5865F2) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentsPanel() {
    return Column(
      children: [
        _buildSliderRow('Brightness', _brightness, -1.0, 1.0, (val) {
          setState(() => _brightness = val);
        }),
        _buildSliderRow('Contrast', _contrast, 0.5, 1.5, (val) {
          setState(() => _contrast = val);
        }),
        _buildSliderRow('Saturation', _saturation, 0.0, 2.0, (val) {
          setState(() => _saturation = val);
        }),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: const Color(0xFF5865F2),
              inactiveColor: Colors.white10,
              onChanged: onChanged,
              onChangeEnd: (_) => _saveHistory(),
            ),
          ),
          Container(
            width: 40,
            alignment: Alignment.centerRight,
            child: Text(
              value.toStringAsFixed(1),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
