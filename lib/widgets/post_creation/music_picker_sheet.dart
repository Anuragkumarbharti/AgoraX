import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/discovery/audio_track_model.dart';
import '../../services/discovery/discovery_service.dart';

class MusicPickerSheet extends StatefulWidget {
  final AudioTrack? selectedTrack;

  const MusicPickerSheet({Key? key, this.selectedTrack}) : super(key: key);

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final DiscoveryService _discoveryService = Get.find<DiscoveryService>();

  AudioTrack? _previewTrack;
  bool _isPlaying = false;
  double _startOffset = 0.0;
  double _endOffset = 30.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _previewTrack = widget.selectedTrack;
    if (_previewTrack != null) {
      _startOffset = _previewTrack!.startOffset.toDouble();
      _endOffset = _previewTrack!.endOffset.toDouble();
    }
    _discoveryService.loadAudioCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _togglePreview(AudioTrack track) {
    if (_previewTrack?.id == track.id && _isPlaying) {
      setState(() => _isPlaying = false);
    } else {
      setState(() {
        _previewTrack = track;
        _startOffset = track.startOffset.toDouble();
        _endOffset = track.endOffset.toDouble();
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Music',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => _discoveryService.loadAudioCatalog(query: val),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, genres...',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Category Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Trending'),
              Tab(text: 'New'),
              Tab(text: 'Popular'),
              Tab(text: 'Saved'),
              Tab(text: 'My Audio'),
            ],
          ),

          // Tracks List
          Expanded(
            child: Obx(() {
              final tracks = _discoveryService.audioCatalog;
              if (tracks.isEmpty) {
                return Center(
                  child: Text(
                    'No audio tracks found',
                    style: GoogleFonts.inter(color: Colors.white38),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isSelected = _previewTrack?.id == track.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor.withOpacity(0.12) : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: AppTheme.primaryColor, width: 1.5) : null,
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.coverUrl.isNotEmpty
                            ? Image.network(track.coverUrl, width: 44, height: 44, fit: BoxFit.cover)
                            : Container(
                                width: 44,
                                height: 44,
                                color: AppTheme.cardBg,
                                child: const Icon(Icons.music_note, color: AppTheme.primaryColor),
                              ),
                      ),
                      title: Text(
                        track.title,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${track.artist} • ${track.duration}s',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _togglePreview(track),
                            icon: Icon(
                              (isSelected && _isPlaying) ? Icons.pause_circle_filled : Icons.play_circle_fill,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, track);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'Use',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),

          // Trim Slider Bar if audio is selected
          if (_previewTrack != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trim Audio Segment',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_startOffset.toInt()}s - ${_endOffset.toInt()}s',
                        style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(_startOffset, _endOffset),
                    min: 0,
                    max: _previewTrack!.duration.toDouble(),
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: Colors.white12,
                    onChanged: (RangeValues values) {
                      setState(() {
                        _startOffset = values.start;
                        _endOffset = values.end;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
