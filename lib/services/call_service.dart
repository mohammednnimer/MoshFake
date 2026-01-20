import 'package:flutter/foundation.dart';
import 'webrtc_service.dart';
import 'signaling_service.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallState {
  idle,
  connecting,
  ringing,
  active,
  ended,
}

class CallService with ChangeNotifier {
  final WebRTCService _webRTCService = WebRTCService();
  final SignalingService _signalingService = SignalingService();
  final NotificationService _notificationService = NotificationService();

  String? _selfUserId;
  CallState _callState = CallState.idle;
  String? _currentCallUserId;
  String? _currentCallPhoneNumber;
  String? _currentCallUserName;
  String? _currentCallId;
  bool _isIncoming = false;
  DateTime? _callStartTime;
  Map<String, dynamic>? _pendingOffer;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _notificationsReady = false;

  CallState get callState => _callState;
  String? get currentCallUserId => _currentCallUserId;
  String? get currentCallPhoneNumber => _currentCallPhoneNumber;
  String? get currentCallUserName => _currentCallUserName;
  String? get currentCallId => _currentCallId;
  bool get isIncoming => _isIncoming;
  DateTime? get callStartTime => _callStartTime;

  Future<void> initialize(String userId) async {
    _selfUserId = userId;
    await _signalingService.connect(userId);
    if (!_notificationsReady) {
      await _notificationService.initialize();
      _notificationsReady = true;
    }
    await _notificationService.updateUserFCMToken(userId);
    _listenToSignalingEvents();
  }

  void _listenToSignalingEvents() {
    _signalingService.incomingCallStream.listen((data) async {
      _isIncoming = true;
      _currentCallId = data['callId'];
      _currentCallUserId = data['fromUserId'];
      _currentCallPhoneNumber = data['fromPhoneNumber'];
      _currentCallUserName = data['callerName'] ?? data['fromPhoneNumber'];
      _callState = CallState.ringing;
      _pendingOffer = null;
      _pendingIceCandidates.clear();
      _remoteDescriptionSet = false;
      notifyListeners();
    });

    _signalingService.offerStream.listen((data) async {
      try {
        _pendingOffer = data['offer'];
        // Force update the signaling target to the sender of the offer (SFU)
        // This ensures our Answer goes back to the SFU, not the original p2p target
        _currentCallUserId = data['fromUserId'];
        _remoteDescriptionSet = false;

        // If the user already tapped answer and the peer connection is ready, handle the offer now
        if (_callState == CallState.connecting &&
            _webRTCService.peerConnection != null) {
          await _handleOfferAndCreateAnswer();
        }
      } catch (e) {
        print('Error handling offer: $e');
      }
    });

    _signalingService.answerStream.listen((data) async {
      try {
        await _webRTCService.setRemoteDescription(data['answer']);
        _pendingOffer = null;
        _remoteDescriptionSet = true;
        await _flushPendingCandidates();
        _callState = CallState.active;
        _callStartTime = DateTime.now();
        notifyListeners();
      } catch (e) {
        print('Error handling answer: $e');
      }
    });

    _signalingService.iceCandidateStream.listen((data) {
      if (!_remoteDescriptionSet || _webRTCService.peerConnection == null) {
        _pendingIceCandidates.add(data['candidate']);
        return;
      }

      _webRTCService.addIceCandidate(data['candidate']);
    });

    _signalingService.callEndedStream.listen((_) {
      endCall();
    });

    _webRTCService.connectionState.listen((isConnected) {
      if (isConnected && _callState == CallState.connecting) {
        _callState = CallState.active;
        _callStartTime = DateTime.now();
        notifyListeners();
      }
    });
  }

  Future<bool> requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    return micStatus.isGranted;
  }

  Future<void> makeCall(String targetPhoneNumber, String callerName) async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        print('Microphone permission denied');
        return;
      }

      _currentCallPhoneNumber = targetPhoneNumber;
      _currentCallUserName =
          targetPhoneNumber; // Display phone until name resolved
      _isIncoming = false;
      _callState = CallState.connecting;
      _pendingOffer = null;
      _pendingIceCandidates.clear();
      _remoteDescriptionSet = false;
      notifyListeners();

      await _webRTCService.initialize();

      // Initiate call and get target user ID
      final callData =
          await _signalingService.initiateCall(targetPhoneNumber, callerName);

      if (callData == null) {
        // User not found
        _callState = CallState.idle;
        notifyListeners();
        print('User not found with phone number: $targetPhoneNumber');
        return;
      }

      _currentCallId = callData['callId'];
      _currentCallUserId = callData['targetUserId'];

      _webRTCService.onIceCandidate((candidate) {
        _signalingService.sendIceCandidate(_currentCallUserId!, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      });

      // Send FCM notification
      await _notificationService.sendCallNotification(
        targetUserId: _currentCallUserId!,
        callerName: callerName,
        callerId: _selfUserId ?? _currentCallUserId!,
      );

      // In SFU mode, we don't create an offer. We wait for the SFU server to send an offer.
      // The server will detect the new call document and initiate the connection.
      print('Waiting for SFU server to initiate connection...');
      
      /* 
      final offer = await _webRTCService.createOffer();
      await _signalingService.sendOffer(_currentCallUserId!, offer);
      */
    } catch (e) {
      print('Error making call: $e');
      _callState = CallState.idle;
      notifyListeners();
    }
  }

  Future<void> answerCall() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        print('Microphone permission denied');
        return;
      }

      _callState = CallState.connecting;
      notifyListeners();

      await _webRTCService.initialize();
      print("WebRTC Service Initialized");
      print('Peer Connection: ${_webRTCService.peerConnection}');

      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      _webRTCService.onIceCandidate((candidate) {
        if (_currentCallUserId != null) {
          _signalingService.sendIceCandidate(_currentCallUserId!, {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      });

      // If we already received the offer while the user was deciding, handle it now
      await _handleOfferAndCreateAnswer();

      // Update call status in Firestore
      if (_currentCallId != null) {
        await _signalingService.acceptCall(_currentCallId!);
      }

      // Cancel notifications
      await _notificationService.cancelAllNotifications();
    } catch (e) {
      print('Error answering call: $e');
      _callState = CallState.idle;
      notifyListeners();
    }
  }

  void endCall() {
    if (_callState == CallState.ended || _callState == CallState.idle) {
      return;
    }

    if (_currentCallUserId != null) {
      _signalingService.endCall(_currentCallId, _currentCallUserId);
    }

    _webRTCService.dispose();
    _notificationService.cancelAllNotifications();

    _pendingOffer = null;
    _pendingIceCandidates.clear();
    _remoteDescriptionSet = false;

    _callState = CallState.ended;
    _currentCallId = null;
    _currentCallUserId = null;
    _currentCallPhoneNumber = null;
    _currentCallUserName = null;
    _isIncoming = false;
    _callStartTime = null;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      _callState = CallState.idle;
      notifyListeners();
    });
  }

  void toggleMute(bool isMuted) {
    _webRTCService.toggleMute(isMuted);
  }

  void toggleSpeaker(bool isSpeakerOn) {
    _webRTCService.toggleSpeaker(isSpeakerOn);
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    _signalingService.dispose();
    super.dispose();
  }

  Future<void> _handleOfferAndCreateAnswer() async {
    if (_pendingOffer == null || _currentCallUserId == null) {
      return;
    }

    await _webRTCService.setRemoteDescription(_pendingOffer!);
    _pendingOffer = null;
    _remoteDescriptionSet = true;
    
    // Create the answer immediately after setting remote description
    final answer = await _webRTCService.createAnswer();
    await _signalingService.sendAnswer(_currentCallUserId!, answer);

    // THEN flush candidates
    await _flushPendingCandidates();

    _callState = CallState.active;
    _callStartTime = DateTime.now();
    notifyListeners();
  }

  Future<void> _flushPendingCandidates() async {
    if (!_remoteDescriptionSet || _webRTCService.peerConnection == null) {
      return;
    }

    for (final candidate
        in List<Map<String, dynamic>>.from(_pendingIceCandidates)) {
      _webRTCService.addIceCandidate(candidate);
    }
    _pendingIceCandidates.clear();
  }
}
