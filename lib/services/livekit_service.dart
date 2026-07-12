import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;
import 'package:supabase_flutter/supabase_flutter.dart';

class LivekitService extends GetxService {
  static LivekitService get to => Get.find<LivekitService>();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RxBool isConnected = false.obs;
  final RxBool isConnecting = false.obs;
  final RxBool isMuted = false.obs;

  MediaStream? get localStream => _localStream;

  Future<void> initializeConnection(String roomId) async {
    isConnecting.value = true;
    try {
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'url': 'stun:stun.l.google.com:19302'},
          {'url': 'stun:stun1.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      // Local stream configuration
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStream!.getAudioTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendSignalingEvent(roomId, 'candidate', candidate.toMap());
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        // Handle remote tracks
      };

      isConnected.value = true;
      print('✅ WebRTC/LiveKit peer connection initialized for room $roomId');
    } catch (e) {
      print('❌ WebRTC/LiveKit connection error: $e');
      rethrow;
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> toggleMic(bool enabled) async {
    if (_localStream == null) return;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = enabled;
    }
    isMuted.value = !enabled;
  }

  Future<void> disconnect() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    isConnected.value = false;
  }

  Future<void> _sendSignalingEvent(String roomId, String type, Map<String, dynamic> data) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.from('room_events').insert({
          'room_id': roomId,
          'user_id': client.auth.currentUser!.id,
          'event_type': 'signaling',
          'payload': {
            'type': type,
            'data': data,
          },
        });
      }
    } catch (_) {}
  }
}
