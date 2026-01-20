import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  // Expose peerConnection for null checking
  RTCPeerConnection? get peerConnection => _peerConnection;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _audioConstraints = {
    'audio': true,
    'video': false,
  };

  Future<void> initialize() async {
    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(_audioConstraints);
      _peerConnection = await createPeerConnection(_iceServers, _config);

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      _peerConnection?.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty && !_remoteStreamController.isClosed) {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream);
        }
      };

      _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        print('ICE Connection State: $state');
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(
              state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                  state == RTCIceConnectionState.RTCIceConnectionStateCompleted);
        }
      };

      print('WebRTC initialized successfully');
    } catch (e) {
      print('Error initializing WebRTC: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOffer() async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      RTCSessionDescription description = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(description);

      return {
        'type': description.type,
        'sdp': description.sdp,
      };
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createAnswer() async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      RTCSessionDescription description = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(description);

      return {
        'type': description.type,
        'sdp': description.sdp,
      };
    } catch (e) {
      print('Error creating answer: $e');
      rethrow;
    }
  }

  Future<void> setRemoteDescription(Map<String, dynamic> session) async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      RTCSessionDescription description = RTCSessionDescription(
        session['sdp'],
        session['type'],
      );
      await _peerConnection!.setRemoteDescription(description);
      print('Remote description set successfully');
    } catch (e) {
      print('Error setting remote description: $e');
      rethrow;
    }
  }

  void addIceCandidate(Map<String, dynamic> candidate) async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      RTCIceCandidate iceCandidate = RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(iceCandidate);
      print('ICE candidate added');
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  void onIceCandidate(Function(RTCIceCandidate) callback) {
    _peerConnection?.onIceCandidate = callback;
  }

  void toggleMute(bool isMuted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !isMuted;
    });
  }

  void toggleSpeaker(bool isSpeakerOn) async {
    try {
      if (_localStream != null) {
        await Helper.setSpeakerphoneOn(isSpeakerOn);
      }
    } catch (e) {
      print('Error toggling speaker: $e');
    }
  }

  MediaStream? get localStream => _localStream;

  Future<void> dispose() async {
    await _localStream?.dispose();
    // _remoteStream is usually just a reference in flutter_webrtc from the event, 
    // explicitly disposing it might invalid tracks if we are not careful, but usually okay.
    // await _remoteStream?.dispose(); 
    
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    
    // IMPORTANT: Do NOT close the broadcast controllers here since CallService reuses this instance.
    // If we close them, we get "Bad state: Cannot add new events after calling close" on the next call.
  }
}
