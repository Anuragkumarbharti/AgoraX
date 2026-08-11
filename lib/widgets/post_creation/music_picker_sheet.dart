import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/discovery/audio_track_model.dart';

class MusicPickerSheet extends StatefulWidget {
  final AudioTrack? initialTrack;

  const MusicPickerSheet({Key? key, this.initialTrack}) : super(key: key);

  static Future<AudioTrack?> show(BuildContext context, {AudioTrack? initialTrack}) async {
    return await showModalBottomSheet<AudioTrack>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MusicPickerSheet(initialTrack: initialTrack),
    );
  }

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  AudioTrack? _selectedTrack;

  final List<AudioTrack> _presetTracks = [
    AudioTrack(
      id: 'track_1',
      title: 'Sunset Lover',
      artist: 'Petit Biscuit',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=300',
      duration: 195,
      usageCount: 124000,
    ),
    AudioTrack(
      id: 'track_2',
      title: 'Creania Waves',
      artist: 'Anurag Kumar',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      duration: 210,
      usageCount: 89000,
    ),
    AudioTrack(
      id: 'track_3',
      title: 'Midnight City',
      artist: 'M83',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      duration: 243,
      usageCount: 450000,
    ),
    AudioTrack(
      id: 'track_4',
      title: 'Flutter Beats',
      artist: 'AgoraX Studio',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300',
      duration: 180,
      usageCount: 67000,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTrack = widget.initialTrack;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchCtrl.text.toLowerCase();

    final filteredTracks = _presetTracks.where((t) {
      return t.title.toLowerCase().contains(query) || t.artist.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Music',
                style: GoogleFonts.outfit(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Bar
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search songs or artists...',
              hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: context.caption),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E2D) : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selected Track Banner if any
          if (_selectedTrack != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTrack!.title,
                          style: GoogleFonts.poppins(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _selectedTrack!.artist,
                          style: GoogleFonts.poppins(
                            color: context.caption,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedTrack),
                    child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      setState(() => _selectedTrack = null);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Track List
          Expanded(
            child: ListView.separated(
              itemCount: filteredTracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = filteredTracks[index];
                final isSelected = _selectedTrack?.id == track.id;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.15)
                      : (isDark ? const Color(0xFF1A1A28) : Colors.grey.shade50),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      track.coverUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        child: const Icon(Icons.music_note, color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  title: Text(
                    track.title,
                    style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${track.artist} • ${track.duration}s',
                    style: GoogleFonts.poppins(
                      color: context.caption,
                      fontSize: 11,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                      : TextButton(
                          onPressed: () {
                            Navigator.pop(context, track);
                          },
                          child: const Text('Select'),
                        ),
                  onTap: () {
                    Navigator.pop(context, track);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
