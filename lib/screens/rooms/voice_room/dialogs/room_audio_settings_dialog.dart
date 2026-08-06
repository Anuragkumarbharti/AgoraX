import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class RoomAudioSettingsDialog extends StatefulWidget {
  final String roomId;
  const RoomAudioSettingsDialog({required this.roomId, Key? key})
      : super(key: key);

  @override
  State<RoomAudioSettingsDialog> createState() =>
      _RoomAudioSettingsDialogState();
}

class _RoomAudioSettingsDialogState extends State<RoomAudioSettingsDialog> {
  double _bgmVolume = 50.0;
  double _voiceVolume = 80.0;
  bool _noiseSuppression = true;
  bool _spatialAudio = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: Get.width * 0.9,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121927),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded,
                        color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Audio & BGM Settings',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Get.back(),
                  child:
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'BGM Volume (${_bgmVolume.round()}%)',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
            Slider(
              value: _bgmVolume,
              min: 0,
              max: 100,
              activeColor: Colors.amberAccent,
              onChanged: (val) => setState(() => _bgmVolume = val),
            ),
            const SizedBox(height: 10),
            Text(
              'Voice Mic Volume (${_voiceVolume.round()}%)',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
            Slider(
              value: _voiceVolume,
              min: 0,
              max: 100,
              activeColor: Colors.pinkAccent,
              onChanged: (val) => setState(() => _voiceVolume = val),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: Text('AI Noise Suppression',
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
              subtitle: Text('Reduce background ambient noise',
                  style:
                      GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
              value: _noiseSuppression,
              activeColor: Colors.cyanAccent,
              onChanged: (val) => setState(() => _noiseSuppression = val),
            ),
            SwitchListTile(
              title: Text('3D Spatial Audio',
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
              subtitle: Text('Immersive voice positioning on seats',
                  style:
                      GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
              value: _spatialAudio,
              activeColor: Colors.purpleAccent,
              onChanged: (val) => setState(() => _spatialAudio = val),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Get.back();
                  Get.snackbar(
                      'Audio Saved', 'Voice & BGM audio levels updated.',
                      snackPosition: SnackPosition.BOTTOM);
                },
                child: Text('Apply Audio Settings',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
